class_name WorldWildernessAccent2D
extends Node2D
## Independent, low-profile CC0 ground accents for wilderness pockets.
##
## This layer intentionally owns no physics, flow-field, resource, or gameplay
## state.  It is separately seeded so future art density does not perturb the
## established BackgroundDecor or AmbientScenery placement streams.

const WILDERNESS_ACCENT_Z: int = -5
const RENDER_CHUNK_SIZE: float = 4096.0
const CAMP_CLEAR_RADIUS: float = 1760.0
const ROAD_EDGE_CLEARANCE: float = 480.0
const WORLD_MARGIN: float = 320.0
const PLACEMENT_ATTEMPTS: int = 96
const TOTAL_ANCHOR_COUNT: int = 24
const MAX_FRAMES_PER_ANCHOR: int = 4
const MINIMUM_ANCHOR_SPAN: float = 112.0
const MAXIMUM_ANCHOR_SPAN: float = 160.0
const WILDERNESS_ACCENT_CHUNK_SCRIPT: Script = preload(
	"res://src/world/world_wilderness_accent_chunk_2d.gd"
)

enum AccentRecipe {
	MOSS_NEST,
	LOW_OUTCROP,
	STONE_RIBBON,
	LICHEN_SCATTER,
}

## These reuse the open-world pockets without modifying their existing
## sequential-RNG consumers. Two or three quiet ground accents per pocket add
## material variation while preserving broad traversal-readable negative space.
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
const ANCHOR_COUNTS_BY_POCKET: Array[int] = [3, 2, 2, 2, 3, 2, 2, 2, 3, 3]

var _half_extent: float = 14336.0
var _camp_position: Vector2 = Vector2.ZERO
var _is_position_walkable: Callable = Callable()
var _road_edge_distance: Callable = Callable()
var _positions: PackedVector2Array = PackedVector2Array()
var _spans: PackedFloat32Array = PackedFloat32Array()
var _rotations: PackedFloat32Array = PackedFloat32Array()
var _recipes: PackedInt32Array = PackedInt32Array()
var _variants: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	z_index = WILDERNESS_ACCENT_Z
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
	_spans.clear()
	_rotations.clear()
	_recipes.clear()
	_variants.clear()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	for pocket_index: int in range(WILDERNESS_POCKETS.size()):
		for pocket_anchor_index: int in range(ANCHOR_COUNTS_BY_POCKET[pocket_index]):
			_scatter_anchor(random, pocket_index, pocket_anchor_index)
	if _positions.size() != TOTAL_ANCHOR_COUNT:
		push_error(
			"Wilderness accent rejected: expected %d safe anchors, found %d"
			% [TOTAL_ANCHOR_COUNT, _positions.size()]
		)
		return
	z_index = WILDERNESS_ACCENT_Z
	z_as_relative = false
	_build_render_chunks()


func get_anchor_count() -> int:
	return _positions.size()


func get_anchor_positions() -> PackedVector2Array:
	return _positions.duplicate()


func get_anchor_spans() -> PackedFloat32Array:
	return _spans.duplicate()


func get_anchor_rotations() -> PackedFloat32Array:
	return _rotations.duplicate()


func get_anchor_recipes() -> PackedInt32Array:
	return _recipes.duplicate()


func get_anchor_variants() -> PackedInt32Array:
	return _variants.duplicate()


func get_anchor_visual_radii() -> PackedFloat32Array:
	var radii: PackedFloat32Array = PackedFloat32Array()
	for span: float in _spans:
		radii.append(_get_visual_radius(span))
	return radii


func get_anchor_frame_counts() -> PackedInt32Array:
	var counts: PackedInt32Array = PackedInt32Array()
	for recipe: int in _recipes:
		counts.append(_get_recipe_frame_count(recipe))
	return counts


func get_render_chunks() -> Array[Node2D]:
	var chunks: Array[Node2D] = []
	for child: Node in get_children():
		var chunk: Node2D = child as Node2D
		if chunk != null:
			chunks.append(chunk)
	return chunks


func get_render_chunk_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for chunk: Node2D in get_render_chunks():
		var bounds_variant: Variant = chunk.call(&"get_world_render_bounds")
		if bounds_variant is Rect2:
			bounds.append(bounds_variant)
	return bounds


func get_chunked_anchor_count() -> int:
	var count: int = 0
	for chunk: Node2D in get_render_chunks():
		var count_variant: Variant = chunk.call(&"get_anchor_count")
		if count_variant is int:
			count += count_variant
	return count


func get_frame_count() -> int:
	var count: int = 0
	for chunk: Node2D in get_render_chunks():
		var count_variant: Variant = chunk.call(&"get_frame_count")
		if count_variant is int:
			count += count_variant
	return count


func is_position_in_wilderness_pocket(world_position: Vector2) -> bool:
	for pocket: Vector4 in WILDERNESS_POCKETS:
		var normalized: Vector2 = Vector2(
			(world_position.x - pocket.x) / pocket.z,
			(world_position.y - pocket.y) / pocket.w
		)
		if normalized.length_squared() <= 1.0:
			return true
	return false


func _scatter_anchor(
	random: RandomNumberGenerator,
	pocket_index: int,
	pocket_anchor_index: int
) -> void:
	var recipe: int = posmod(pocket_index * 3 + pocket_anchor_index, AccentRecipe.size())
	if _get_recipe_frame_count(recipe) > MAX_FRAMES_PER_ANCHOR:
		push_error("Wilderness accent recipe exceeds its mobile frame budget")
		return
	var span: float = random.randf_range(MINIMUM_ANCHOR_SPAN, MAXIMUM_ANCHOR_SPAN)
	var candidate: Vector2 = _sample_anchor(
		random,
		WILDERNESS_POCKETS[pocket_index],
		span
	)
	if not candidate.is_finite():
		push_error("Wilderness accent rejected an unsafe pocket anchor")
		return
	_positions.append(candidate)
	_spans.append(span)
	_rotations.append(random.randf_range(-0.24, 0.24))
	_recipes.append(recipe)
	_variants.append(pocket_index * 11 + pocket_anchor_index * 3)


func _sample_anchor(
	random: RandomNumberGenerator,
	pocket: Vector4,
	span: float
) -> Vector2:
	for attempt: int in range(PLACEMENT_ATTEMPTS):
		var angle: float = random.randf_range(0.0, TAU)
		var radius_factor: float = lerpf(0.12, 0.76, pow(random.randf(), 1.18))
		var candidate: Vector2 = Vector2(pocket.x, pocket.y) + Vector2(
			cos(angle) * pocket.z * radius_factor,
			sin(angle) * pocket.w * radius_factor
		)
		if _is_candidate_valid(candidate, span):
			return candidate
	for fallback_index: int in range(64):
		var fallback_angle: float = float(fallback_index) * 2.399963
		var fallback_radius: float = 0.14 + float(fallback_index % 9) * 0.065
		var fallback: Vector2 = Vector2(pocket.x, pocket.y) + Vector2(
			cos(fallback_angle) * pocket.z * minf(fallback_radius, 0.78),
			sin(fallback_angle) * pocket.w * minf(fallback_radius, 0.78)
		)
		if _is_candidate_valid(fallback, span):
			return fallback
	push_error("Wilderness accent could not find a safe wilderness pocket position")
	return Vector2.INF


func _is_candidate_valid(candidate: Vector2, span: float) -> bool:
	if not candidate.is_finite():
		return false
	if absf(candidate.x) > _half_extent - WORLD_MARGIN or absf(candidate.y) > _half_extent - WORLD_MARGIN:
		return false
	if candidate.distance_squared_to(_camp_position) < CAMP_CLEAR_RADIUS * CAMP_CLEAR_RADIUS:
		return false
	if not _road_edge_distance.is_valid() or not _is_position_walkable.is_valid():
		return false
	var road_distance_variant: Variant = _road_edge_distance.call(candidate)
	if not road_distance_variant is float and not road_distance_variant is int:
		return false
	if float(road_distance_variant) < ROAD_EDGE_CLEARANCE:
		return false
	## This is only an overlap query: it never creates a footprint or mutates
	## flow. The complete rendered radius stays outside authored geometry so a
	## non-colliding ground accent cannot visually impersonate an obstacle.
	var walkable_variant: Variant = _is_position_walkable.call(
		candidate,
		_get_visual_radius(span)
	)
	if not walkable_variant is bool or not walkable_variant:
		return false
	for existing_index: int in range(_positions.size()):
		var minimum_separation: float = maxf(300.0, span * 1.15)
		if candidate.distance_squared_to(_positions[existing_index]) < minimum_separation * minimum_separation:
			return false
	return true


func _get_visual_radius(span: float) -> float:
	return span * 0.90 + 38.0


func _get_recipe_frame_count(recipe: int) -> int:
	match recipe:
		AccentRecipe.LOW_OUTCROP:
			return 4
		AccentRecipe.LICHEN_SCATTER:
			return 2
		_:
			return 3


func _build_render_chunks() -> void:
	var chunks_by_coordinate: Dictionary = {}
	for anchor_index: int in range(_positions.size()):
		var anchor_position: Vector2 = _positions[anchor_index]
		var chunk: Node2D = _get_or_create_chunk(anchor_position, chunks_by_coordinate)
		chunk.call(
			&"add_anchor",
			anchor_position,
			_spans[anchor_index],
			_rotations[anchor_index],
			_recipes[anchor_index],
			_variants[anchor_index]
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
	var chunk: Node2D = WILDERNESS_ACCENT_CHUNK_SCRIPT.new() as Node2D
	chunk.name = "WildernessAccentChunk_%02d_%02d" % [coordinate.x, coordinate.y]
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
