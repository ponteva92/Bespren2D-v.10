class_name WorldGroundCover2D
extends Node2D
## Dense authored ground cover for the map's natural terrain.
##
## The measured defect this layer answers: at the shipped gameplay zoom of
## `Vector2(0.38, 0.38)` the 480x270 frame covers roughly 1,263 by 710 world
## units, and the existing decorative families put about five elements inside
## it - four ambient props and one background decoration - even when the camera
## is aimed directly at `WILDERNESS_POCKETS[4]`, which is the dense case rather
## than the sparse one. The ground was carrying the whole frame.
##
## This is a separate family rather than larger counts on the existing ones for
## the reason `WorldWildernessAccent2D` already records: the established decor
## and scenery placement streams are sequential RNG consumers, and
## `polyhaven_district_validation.gd` asserts exact bench, hydrant, and stove
## counts inside the background totals, so inflating either one would move
## art that is already pinned. Like that layer, this one owns no physics,
## flow-field, resource, or gameplay state, is configured only after the
## canonical obstacle and flow-field pipeline has finished, and reads the map
## contract without writing to it.

const GROUND_COVER_Z: int = -5
const RENDER_CHUNK_SIZE: float = 2048.0
## One cluster candidate per cell.
## Density is raised through elements first and cells second, because the two
## costs are not comparable. An extra element is two more points inside an
## existing `draw_multiline` batch and costs no placement work at all; an extra
## cell costs a road-distance sweep and an occupancy query at world build, which
## is startup time on the device.
## Measured rather than predicted, because the earlier note here was neither.
## It claimed this 256-unit cell would put "roughly eleven clusters and a
## hundred and thirty" elements in the shipped gameplay frame; the built world
## is 3,245 clusters and 38,947 elements, of which 8 clusters and about 63
## elements fall inside the 1263x711 world units the 0.38 gameplay zoom covers.
## A separate complaint that only about five of those actually read was true
## when it was made and is no longer: it described the first colour pass, before
## the value-pair authoring in [WorldGroundCoverChunk2D] gave every kind a lit
## and a shaded face against the measured ground. The current gameplay capture
## carries 4.42 percent of its pixels at least 18 luma above the modal ground
## and 7.10 percent at least 8 below it, across 2,761 separate lit runs. So the
## cover was never too sparse - it was too close in value to the floor it sat
## on, and raising density would have multiplied something invisible. These
## constants stay where they are.
const CLUSTER_CELL_SIZE: float = 256.0
const CLUSTER_FILL_RATIO: float = 0.48
const CAMP_CLEAR_RADIUS: float = 520.0
## Deliberately small. This is cover, not an obstacle: it should reach the road
## verge the way real ground does instead of leaving the wide clearance ring an
## occluding prop needs.
const ROAD_EDGE_CLEARANCE: float = 60.0
const WORLD_MARGIN: float = 160.0
const MINIMUM_NATURAL_WEIGHT: float = 0.55
const MINIMUM_CLUSTER_RADIUS: float = 62.0
const MAXIMUM_CLUSTER_RADIUS: float = 138.0
const MINIMUM_ELEMENTS_PER_CLUSTER: int = 6
const MAXIMUM_ELEMENTS_PER_CLUSTER: int = 18
const MINIMUM_CLUSTER_COUNT: int = 1400
const MAXIMUM_CLUSTER_COUNT: int = 9000
const BIOME_MASK: Texture2D = preload(
	"res://assets/2d/environment/terrain/bespren_biome_blend_mask.png"
)
const GROUND_COVER_CHUNK_SCRIPT: Script = preload(
	"res://src/world/world_ground_cover_chunk_2d.gd"
)

enum CoverKind {
	GRASS_TUFT,
	LEAF_LITTER,
	PEBBLE_SCATTER,
	TWIG_FALL,
}

var _half_extent: float = 14336.0
var _camp_position: Vector2 = Vector2.ZERO
var _is_position_walkable: Callable = Callable()
var _road_edge_distance: Callable = Callable()
var _biome_image: Image = null
var _positions: PackedVector2Array = PackedVector2Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _kinds: PackedInt32Array = PackedInt32Array()
var _counts: PackedInt32Array = PackedInt32Array()
var _seeds: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	z_index = GROUND_COVER_Z
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
	_radii.clear()
	_kinds.clear()
	_counts.clear()
	_seeds.clear()
	_biome_image = BIOME_MASK.get_image()
	var cell_dimension: int = maxi(
		1,
		floori((_half_extent * 2.0) / CLUSTER_CELL_SIZE)
	)
	for cell_y: int in range(cell_dimension):
		for cell_x: int in range(cell_dimension):
			_consider_cell(cell_x, cell_y, seed_value)
	if _positions.size() < MINIMUM_CLUSTER_COUNT:
		push_error(
			"Ground cover rejected: expected at least %d clusters, found %d"
			% [MINIMUM_CLUSTER_COUNT, _positions.size()]
		)
		return
	z_index = GROUND_COVER_Z
	z_as_relative = false
	_build_render_chunks()


func get_cluster_count() -> int:
	return _positions.size()


func get_cluster_positions() -> PackedVector2Array:
	return _positions.duplicate()


func get_cluster_radii() -> PackedFloat32Array:
	return _radii.duplicate()


func get_cluster_kinds() -> PackedInt32Array:
	return _kinds.duplicate()


func get_element_count() -> int:
	var total: int = 0
	for count: int in _counts:
		total += count
	return total


func get_render_chunks() -> Array[Node2D]:
	var chunks: Array[Node2D] = []
	for child: Node in get_children():
		var chunk: Node2D = child as Node2D
		if chunk != null:
			chunks.append(chunk)
	return chunks


func get_chunked_cluster_count() -> int:
	var total: int = 0
	for chunk: Node2D in get_render_chunks():
		var count_variant: Variant = chunk.call(&"get_cluster_count")
		if count_variant is int:
			total += count_variant
	return total


func get_command_count() -> int:
	var total: int = 0
	for chunk: Node2D in get_render_chunks():
		var count_variant: Variant = chunk.call(&"get_command_count")
		if count_variant is int:
			total += count_variant
	return total


func get_render_chunk_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for chunk: Node2D in get_render_chunks():
		var bounds_variant: Variant = chunk.call(&"get_world_render_bounds")
		if bounds_variant is Rect2:
			bounds.append(bounds_variant)
	return bounds


func _consider_cell(cell_x: int, cell_y: int, seed_value: int) -> void:
	if _positions.size() >= MAXIMUM_CLUSTER_COUNT:
		return
	var cell_seed: int = seed_value + cell_y * 8191 + cell_x * 31
	if WorldGroundCoverChunk2D.hash_unit(cell_seed) > CLUSTER_FILL_RATIO:
		return
	var cell_origin: Vector2 = Vector2(-_half_extent, -_half_extent) + Vector2(
		float(cell_x) * CLUSTER_CELL_SIZE,
		float(cell_y) * CLUSTER_CELL_SIZE
	)
	var candidate: Vector2 = cell_origin + Vector2(
		(0.18 + WorldGroundCoverChunk2D.hash_unit(cell_seed + 3) * 0.64) * CLUSTER_CELL_SIZE,
		(0.18 + WorldGroundCoverChunk2D.hash_unit(cell_seed + 5) * 0.64) * CLUSTER_CELL_SIZE
	)
	var radius: float = lerpf(
		MINIMUM_CLUSTER_RADIUS,
		MAXIMUM_CLUSTER_RADIUS,
		WorldGroundCoverChunk2D.hash_unit(cell_seed + 7)
	)
	if absf(candidate.x) > _half_extent - WORLD_MARGIN:
		return
	if absf(candidate.y) > _half_extent - WORLD_MARGIN:
		return
	if candidate.distance_squared_to(_camp_position) < CAMP_CLEAR_RADIUS * CAMP_CLEAR_RADIUS:
		return
	## The biome sample is by far the cheapest rejection, so it runs before the
	## road-distance sweep and the occupancy query.
	var weights: Vector2 = _sample_biome_weights(candidate)
	if weights.x < MINIMUM_NATURAL_WEIGHT:
		return
	if not _is_clear_of_authored_geometry(candidate, radius):
		return
	_positions.append(candidate)
	_radii.append(radius)
	_kinds.append(_select_kind(cell_seed, weights.y))
	_counts.append(
		MINIMUM_ELEMENTS_PER_CLUSTER + int(
			WorldGroundCoverChunk2D.hash_unit(cell_seed + 9)
			* float(MAXIMUM_ELEMENTS_PER_CLUSTER - MINIMUM_ELEMENTS_PER_CLUSTER + 1)
		)
	)
	_seeds.append(cell_seed)


func _is_clear_of_authored_geometry(candidate: Vector2, radius: float) -> bool:
	if not _road_edge_distance.is_valid() or not _is_position_walkable.is_valid():
		return false
	var road_distance_variant: Variant = _road_edge_distance.call(candidate)
	if not road_distance_variant is float and not road_distance_variant is int:
		return false
	if float(road_distance_variant) < ROAD_EDGE_CLEARANCE:
		return false
	## An overlap query only. It never creates a footprint and never mutates
	## flow, and the whole drawn radius stays outside authored geometry so a
	## non-colliding cover cluster cannot visually impersonate an obstacle.
	var walkable_variant: Variant = _is_position_walkable.call(candidate, radius)
	return walkable_variant is bool and walkable_variant


## Returns (natural weight, forest share) with both normalised across the four
## authored channels. The mask imports uncompressed with mipmaps off, so the
## values read here are the same ones `terrain_material_blend.gdshader`
## samples - the cover cannot land on ground the shader paints as pavement.
func _sample_biome_weights(world_position: Vector2) -> Vector2:
	if _biome_image == null:
		return Vector2.ZERO
	var mask_size: Vector2i = _biome_image.get_size()
	if mask_size.x <= 0 or mask_size.y <= 0:
		return Vector2.ZERO
	var span: float = maxf(_half_extent * 2.0, 1.0)
	var pixel: Color = _biome_image.get_pixel(
		clampi(
			floori((world_position.x + _half_extent) / span * float(mask_size.x)),
			0,
			mask_size.x - 1
		),
		clampi(
			floori((world_position.y + _half_extent) / span * float(mask_size.y)),
			0,
			mask_size.y - 1
		)
	)
	var forest: float = pixel.r
	var mud: float = maxf(1.0 - pixel.r - pixel.g - pixel.b, 0.0)
	var total: float = pixel.r + pixel.g + pixel.b + mud
	if total <= 0.0:
		return Vector2.ZERO
	return Vector2((forest + mud) / total, forest / total)


## Forest floor grows and sheds; bare mud carries stone and deadfall instead.
func _select_kind(cell_seed: int, forest_share: float) -> int:
	var roll: float = WorldGroundCoverChunk2D.hash_unit(cell_seed + 13)
	var grass_share: float = lerpf(0.16, 0.60, forest_share)
	if roll < grass_share:
		return CoverKind.GRASS_TUFT
	var litter_edge: float = grass_share + lerpf(0.10, 0.24, forest_share)
	if roll < litter_edge:
		return CoverKind.LEAF_LITTER
	if roll < litter_edge + lerpf(0.44, 0.10, forest_share):
		return CoverKind.PEBBLE_SCATTER
	return CoverKind.TWIG_FALL


func _build_render_chunks() -> void:
	var chunks_by_coordinate: Dictionary = {}
	for cluster_index: int in range(_positions.size()):
		var cluster_position: Vector2 = _positions[cluster_index]
		var chunk: Node2D = _get_or_create_chunk(cluster_position, chunks_by_coordinate)
		chunk.call(
			&"add_cluster",
			cluster_position,
			_radii[cluster_index],
			_kinds[cluster_index],
			_counts[cluster_index],
			_seeds[cluster_index]
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
	var chunk: Node2D = GROUND_COVER_CHUNK_SCRIPT.new() as Node2D
	chunk.name = "GroundCoverChunk_%02d_%02d" % [coordinate.x, coordinate.y]
	add_child(chunk)
	chunk.call(
		&"configure_origin",
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
