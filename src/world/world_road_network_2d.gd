class_name WorldRoadNetwork2D
extends Node2D
## Authored road topology rendered through bounded mobile-friendly child chunks.

const ASPHALT_OUTER_WIDTH: float = 540.0
const ASPHALT_INNER_WIDTH: float = 420.0
const DIRT_OUTER_WIDTH: float = 480.0
const DIRT_INNER_WIDTH: float = 360.0
const DASH_LENGTH: float = 220.0
const DASH_GAP: float = 250.0
const MAX_RENDER_CHUNK_LENGTH: float = 4096.0

var _routes: Array[PackedVector2Array] = []
var _dirt_flags: PackedByteArray = PackedByteArray()


func _ready() -> void:
	z_index = -20
	z_as_relative = false


func configure(routes: Array[PackedVector2Array], dirt_flags: PackedByteArray) -> void:
	_clear_render_chunks()
	_routes.clear()
	for route: PackedVector2Array in routes:
		_routes.append(route.duplicate())
	_dirt_flags = dirt_flags.duplicate()
	z_index = -20
	z_as_relative = false
	_build_render_chunks()


func get_route_count() -> int:
	return _routes.size()


func get_routes() -> Array[PackedVector2Array]:
	var copy: Array[PackedVector2Array] = []
	for route: PackedVector2Array in _routes:
		copy.append(route.duplicate())
	return copy


func get_dirt_flags() -> PackedByteArray:
	return _dirt_flags.duplicate()


func get_minimum_road_edge_distance(world_position: Vector2) -> float:
	return _minimum_edge_distance(world_position, true)


func get_minimum_asphalt_edge_distance(world_position: Vector2) -> float:
	return _minimum_edge_distance(world_position, false)


func _minimum_edge_distance(world_position: Vector2, include_dirt: bool) -> float:
	## Returns physical clearance from a point to the nearest rendered outer
	## road edge, rather than merely measuring to its centerline.
	if not world_position.is_finite():
		return 0.0
	var shortest: float = INF
	for route_index: int in range(_routes.size()):
		var is_dirt: bool = (
			route_index < _dirt_flags.size()
			and _dirt_flags[route_index] == 1
		)
		if is_dirt and not include_dirt:
			continue
		var route: PackedVector2Array = _routes[route_index]
		var outer_half_width: float = (
			DIRT_OUTER_WIDTH if is_dirt else ASPHALT_OUTER_WIDTH
		) * 0.5
		for point_index: int in range(route.size() - 1):
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
				world_position,
				route[point_index],
				route[point_index + 1]
			)
			shortest = minf(
				shortest,
				maxf(0.0, world_position.distance_to(closest) - outer_half_width)
			)
	return shortest


func get_render_chunk_count() -> int:
	return get_child_count()


func get_render_chunk_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for child: Node in get_children():
		var chunk: WorldRoadSegmentChunk2D = child as WorldRoadSegmentChunk2D
		if chunk != null:
			bounds.append(chunk.get_world_render_bounds())
	return bounds


func get_render_chunks() -> Array[WorldRoadSegmentChunk2D]:
	var chunks: Array[WorldRoadSegmentChunk2D] = []
	for child: Node in get_children():
		var chunk: WorldRoadSegmentChunk2D = child as WorldRoadSegmentChunk2D
		if chunk != null:
			chunks.append(chunk)
	return chunks


func _build_render_chunks() -> void:
	var chunk_index: int = 0
	for route_index: int in range(_routes.size()):
		var route: PackedVector2Array = _routes[route_index]
		if route.size() < 2:
			continue
		var is_dirt: bool = route_index < _dirt_flags.size() and _dirt_flags[route_index] == 1
		for point_index: int in range(route.size() - 1):
			var start: Vector2 = route[point_index]
			var finish: Vector2 = route[point_index + 1]
			var displacement: Vector2 = finish - start
			var length: float = displacement.length()
			if length <= 0.0:
				continue
			var direction: Vector2 = displacement / length
			var subdivision_count: int = maxi(1, ceili(length / MAX_RENDER_CHUNK_LENGTH))
			for subdivision: int in range(subdivision_count):
				var start_distance: float = minf(
					float(subdivision) * MAX_RENDER_CHUNK_LENGTH,
					length
				)
				var finish_distance: float = minf(
					float(subdivision + 1) * MAX_RENDER_CHUNK_LENGTH,
					length
				)
				var chunk: WorldRoadSegmentChunk2D = WorldRoadSegmentChunk2D.new()
				chunk.name = "RoadChunk_%03d" % chunk_index
				add_child(chunk)
				chunk.configure(
					start + direction * start_distance,
					start + direction * finish_distance,
					is_dirt,
					DIRT_OUTER_WIDTH if is_dirt else ASPHALT_OUTER_WIDTH,
					DIRT_INNER_WIDTH if is_dirt else ASPHALT_INNER_WIDTH,
					DASH_LENGTH,
					DASH_GAP,
					start_distance
				)
				chunk_index += 1


func _clear_render_chunks() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
